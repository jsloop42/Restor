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
    private lazy var ck = { return EACloudKit.shared }()
    private let nc = NotificationCenter.default
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
    var defaultZoneCursor: CKQueryOperation.Cursor?
    private let store = UserDefaults.standard
    private let lastSyncedKey = "last-synced-key"
    private let lastSyncTimeKey = "last-sync-time-key"
    private let defaultQueryCursorKey = "default-query-cursor-key"
    private let syncRecordKey = "sync-record-key"
    private let defaultZoneRecordFetchLimit = 50
    private let opQueue = EAOperationQueue()
    private var syncTimer: DispatchSourceTimer?
    private var isSyncFromCloudSuccess = false
    private var isSyncToCloudSuccess = false
    private var isSyncTimeSet = false
    private var queryDefaultZoneRecordRepeatTimer: EARepeatTimer!
    private var fetchZoneChangesDelayTimer: EARescheduler!
    private var isSyncToCloudTriggered = false  // On app launch, is syncing to cloud initialised
    private var isSyncToCloudInProgress = false  // If processing of syncing to cloud in progress (adding to queue part).
    private var syncToCloudTimer: EARepeatTimer!
    private var syncToCloudCtx: NSManagedObjectContext!
    // Using same context so that, we do not get dangling reference to invalid object issue which occurs when referenced object is in another context,
    // and saving it between zones, so that we do not get attempting to serialize access on non-owning coordinator issues.
    private var syncFromCloudCtx: NSManagedObjectContext!
    private var wsSyncFrc: NSFetchedResultsController<EWorkspace>!
    private var projSyncFrc: NSFetchedResultsController<EProject>!
    private var reqSyncFrc: NSFetchedResultsController<ERequest>!
    private var historySyncFrc: NSFetchedResultsController<EHistory>!
    private var envSyncFrc: NSFetchedResultsController<EEnv>!
    private var envVarSyncFrc: NSFetchedResultsController<EEnvVar>!
    private var projDelFrc: NSFetchedResultsController<EProject>!  // Since the back reference gets removed, we need to query them separately
    private var reqDelFrc: NSFetchedResultsController<ERequest>!
    private var reqDataDelFrc: NSFetchedResultsController<ERequestData>!
    private var reqBodyDataDelFrc: NSFetchedResultsController<ERequestBodyData>!
    private var reqMethodDataDelFrc: NSFetchedResultsController<ERequestMethodData>!
    private var fileDelFrc: NSFetchedResultsController<EFile>!
    private var imageDelFrc: NSFetchedResultsController<EImage>!
    private var histDelFrc: NSFetchedResultsController<EHistory>!
    private var envDelFrc: NSFetchedResultsController<EEnv>!
    private var envVarDelFrc: NSFetchedResultsController<EEnvVar>!
    private var wsSyncIdx = 0
    private var projSyncIdx = 0
    private var reqSyncIdx = 0
    private var historySyncIdx = 0
    private var envSyncIdx = 0
    private var envVarSyncIdx = 0
    private var projDelSyncIdx = 0
    private var reqDelSyncIdx = 0
    private var reqDataDelSyncIdx = 0
    private var reqBodyDataDelSyncIdx = 0
    private var reqMethodDataDelSyncIdx = 0
    private var fileDelSyncIdx = 0
    private var imageDelSyncIdx = 0
    private var historyDelSyncIdx = 0
    private var envDelSyncIdx = 0
    private var envVarDelSyncIdx = 0
    private var hasMoreZonesToQuery = false
    private var zonesToSync: [CKRecord] = []
    private var zonesToSyncInProgress: Set<CKRecord> = Set()
    private var syncToCloudSaveIds: Set<String> = Set()
    private var syncToCloudDeleteIds: Set<String> = Set()
    private var destroySyncStateLock = NSLock()
    
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
        case historyChange = "history-change"
        case envChange = "env-change"
        case envVarChange = "env-var-change"
        
        static var allCases: [String] {
            return [SubscriptionId.fileChange.rawValue, SubscriptionId.imageChange.rawValue, SubscriptionId.projectChange.rawValue,
                    SubscriptionId.requestChange.rawValue, SubscriptionId.requestBodyChange.rawValue, SubscriptionId.requestDataChange.rawValue,
                    SubscriptionId.requestMethodChange.rawValue, SubscriptionId.workspaceChange.rawValue, SubscriptionId.databaseChange.rawValue,
                    SubscriptionId.historyChange.rawValue, SubscriptionId.envChange.rawValue, SubscriptionId.envVarChange.rawValue]
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
        case history = "history-cursor-key"
        case env = "env-cursor-key"
        case envVar = "env-var-cursor-key"
        
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
            case .history:
                self = .history
            case .env:
                self = .env
            case .envVar:
                self = .envVar
            }
        }
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    init() {
        if isRunningTests { return }
        self.initEvents()
        self.initSaveQueue()
        self.subscribeToCloudKitEvents()
        self.syncFromCloud()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.networkDidBecomeAvailable(_:)), name: .online, object: nil)
        self.nc.addObserver(self, selector: #selector(self.networkDidBecomeUnavailable(_:)), name: .offline, object: nil)
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
    
    @objc func networkDidBecomeUnavailable(_ notif: Notification) {
        self.destroySyncToCloudState()
    }
    
    @objc func networkDidBecomeAvailable(_ notif: Notification) {
        self.isSyncToCloudTriggered = false
        self.syncToCloud()
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
                    Log.debug("Save to cloud success: \(xs.count) - \(self.syncToCloudSaveIds)")
                    // Update the entities' attribute and cache
                    var id: String!
                    xs.forEach { record in
                        if let map = entityMap[record.recordID] {
                            if let entity = map.entity {
                                let ctx = entity.managedObjectContext
                                ctx?.performAndWait {
                                    id = entity.getId()
                                    Log.debug("saved entity: \(id!)")
                                    self.syncToCloudSaveIds.remove(id)
                                    entity.setIsSynced(true)
                                    if let type = RecordType(rawValue: record.recordType) {
                                        self.addToCache(record: record, entityId: id, type: type)
                                        if type == .workspace { self.localdb.setWorkspaceActive(id, ctx: ctx) }
                                        if type == .zone {
                                            if let ws = self.localdb.getWorkspace(id: id, ctx: ctx) {
                                                ws.isZoneSynced = true
                                                self.localdb.saveMainContext()
                                            }
                                        }
                                    }
                                    if let _ = self.syncToCloudSaveIds.remove(id) { self.checkSyncToCloudState() }
                                }
                            } else {
                                Log.debug("Likely a save after a zone record not found error. Re-sync.")
                                let ctx = self.localdb.mainMOC
                                ctx.performAndWait {
                                    if let type = RecordType[record.type()], type == .zone {
                                        if let ws = self.localdb.getWorkspace(id: record.id(), ctx: ctx) {
                                            ws.isZoneSynced = true
                                            self.localdb.saveMainContext()
                                        }
                                        self.syncFromCloud()
                                    }
                                }
                            }
                            map.completion?()
                        }
                    }
                    self.checkSyncToCloudState()
                case .failure(let error):
                    if let err = error as? CKError {
                        if err.isSameRecord() {
                            guard let name = err.getRecordNameForSameRecordError() else { return }
                            let id = self.ck.entityID(recordName: name)
                            self.syncToCloudSaveIds.remove(id)
                            guard let recordType = RecordType.from(id: id) else { return }
                            self.localdb.mainMOC.performAndWait {
                                if let elem = self.localdb.getEntity(recordType: recordType, id: id, ctx: self.localdb.mainMOC) {
                                    elem.setIsSynced(true)
                                    if recordType == .workspace, let ws = elem as? EWorkspace, !ws.isZoneSynced { self.saveZoneToCloud(ws) }
                                    self.localdb.saveMainContext()
                                }
                            }
                        }
                    }
                    self.checkSyncToCloudState()
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
        case .zone, .history, .env, .envVar:
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
        case .zone, .history, .env, .envVar:
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
                        if op.opType == .queryRecord {
                            op.completionHandler = self.syncFromCloudHandler(_:)
                        }
                        if self.opQueue.add(op) { hm.removeValue(forKey: op.getKey()) }
                    }
                }
                self.store.set(hm, forKey: self.syncRecordKey)
                if hm.isEmpty { self.syncTimer?.cancel(); self.syncTimer = nil }
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
    
    // MARK: - Sync to cloud
    
    func initSyncToCloudState() {
        if self.isSyncToCloudTriggered { return }
        Log.debug("init sync to cloud state")
        DispatchQueue.global().sync {
            if self.syncToCloudTimer != nil { self.destroySyncToCloudState() }
        }
        if syncToCloudTimer == nil {
            self.syncToCloudTimer = EARepeatTimer(block: { [weak self] in self?.syncToCloud() }, interval: 5, limit: 18)  // 3 mins
        }
        self.syncToCloudTimer.done = {
            Log.debug("Sync to cloud timer max limit - saves: \(self.syncToCloudSaveIds), deletes: \(self.syncToCloudDeleteIds)")
            self.syncToCloudTimer = nil
            self.syncToCloudSaveIds = Set()
            self.syncToCloudDeleteIds = Set()
            self.localdb.saveMainContext()
        }
        if self.syncToCloudCtx == nil { self.syncToCloudCtx = self.localdb.mainMOC }
        self.syncToCloudTimer.resume()
        self.isSyncToCloudTriggered = true
    }
    
    func destroySyncToCloudState() {
        Log.debug("destroy sync to cloud state")
        self.destroySyncStateLock.lock()
        if self.syncToCloudTimer != nil { self.syncToCloudTimer.suspend() }
        self.destroySyncStateLock.unlock()
    }
    
    func syncToCloud() {
        Log.debug("sync to cloud")
        if self.saveQueue.count > 16 { return }
        if !self.zonesToSync.isEmpty { return }
        self.initSyncToCloudState()
        self.isSyncToCloudInProgress = true
        if self.wsSyncFrc == nil { self.wsSyncFrc = self.localdb.getWorkspacesToSync(ctx: self.syncToCloudCtx) }
        var count = 0
        var len = 0
        var start = 0
        var done: Bool = true  // sync visit complete
        self.syncToCloudCtx.perform {
            if let xs = self.wsSyncFrc.fetchedObjects {
                start = self.wsSyncIdx
                len = xs.count
                var ws: EWorkspace!
                for i in start..<len {
                    ws = xs[i]
                    self.saveWorkspaceToCloud(ws)
                    self.syncToCloudSaveIds.insert(ws.getId())
                    self.wsSyncIdx += 1
                    if count == 3 { break }
                    count += 1
                }
                if done && self.wsSyncIdx < len { done = false }
            }
        }
        if self.projSyncFrc == nil { self.projSyncFrc = self.localdb.getProjectsToSync(ctx: self.syncToCloudCtx) }
        self.syncToCloudCtx.perform {
            if let xs = self.projSyncFrc.fetchedObjects {
                start = self.projSyncIdx
                len = xs.count
                count = 0
                var proj: EProject!
                for i in start..<len {
                    proj = xs[i]
                    self.saveProjectToCloud(proj)
                    self.syncToCloudSaveIds.insert(proj.getId())
                    self.projSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.projSyncIdx < len { done = false }
            }
        }
        if self.reqSyncFrc == nil { self.reqSyncFrc = self.localdb.getRequestsToSync(ctx: self.syncToCloudCtx) }
        self.syncToCloudCtx.perform {
            if let xs = self.reqSyncFrc.fetchedObjects {
                start = self.reqSyncIdx
                len = xs.count
                count = 0
                var req: ERequest!
                for i in start..<len {
                    req = xs[i]
                    self.saveRequestToCloud(req)
                    self.syncToCloudSaveIds.insert(req.getId())
                    self.reqSyncIdx += 1
                    if count == 3 { break }
                    count += 1
                }
                if done && self.reqSyncIdx < len { done = false }
            }
        }
        if self.historySyncFrc == nil { self.historySyncFrc = self.localdb.getHistoriesToSync(ctx: self.syncToCloudCtx) }
        self.syncToCloudCtx.perform {
            if let xs = self.historySyncFrc.fetchedObjects {
                start = self.historySyncIdx
                len = xs.count
                count = 0
                var hist: EHistory!
                for i in start..<len {
                    hist = xs[i]
                    self.saveHistoryToCloud(hist)
                    self.syncToCloudSaveIds.insert(hist.getId())
                    self.historySyncIdx += 1
                    if count == 3 { break }
                    count += 1
                }
                if done && self.historySyncIdx < len { done = false }
            }
        }
        if self.envSyncFrc == nil { self.envSyncFrc = self.localdb.getEnvsToSync(ctx: self.syncToCloudCtx) }
        self.syncToCloudCtx.perform {
            if let xs = self.envSyncFrc.fetchedObjects {
                start = self.envSyncIdx
                len = xs.count
                count = 0
                var env: EEnv!
                for i in start..<len {
                    env = xs[i]
                    self.saveEnvToCloud(env)
                    self.syncToCloudSaveIds.insert(env.getId())
                    self.envSyncIdx += 1
                    if count == 3 { break }
                    count += 1
                }
                if done && self.envSyncIdx < len { done = false }
            }
        }
        if self.envVarSyncFrc == nil { self.envVarSyncFrc = self.localdb.getEnvVarsToSync(ctx: self.syncToCloudCtx) }
        self.syncToCloudCtx.perform {
            if let xs = self.envVarSyncFrc.fetchedObjects {
                start = self.envVarSyncIdx
                len = xs.count
                count = 0
                var envVar: EEnvVar!
                for i in start..<len {
                    envVar = xs[i]
                    self.saveEnvVarToCloud(envVar)
                    self.syncToCloudSaveIds.insert(envVar.getId())
                    self.envVarSyncIdx += 1
                    if count == 3 { break }
                    count += 1
                }
                if done && self.envVarSyncIdx < len { done = false }
            }
        }
        // Delete entites marked for delete
        var delxs: [Entity] = []
        let deleteEntities: () -> Void = {
            if delxs.count > 15 {
                self.deleteEntitesFromCloud(delxs, ctx: self.syncToCloudCtx)
                delxs = []
            }
        }
        // Project
        if self.projDelFrc == nil { self.projDelFrc = self.localdb.getDataMarkedForDelete(obj: EProject.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EProject> }
        self.syncToCloudCtx.perform {
            if self.projDelFrc != nil, let xs = self.projDelFrc.fetchedObjects {
                start = self.projDelSyncIdx
                len = xs.count
                var proj: EProject!
                for i in start..<len {
                    proj = xs[i]
                    delxs.append(proj)
                    self.syncToCloudDeleteIds.insert(proj.getId())
                    self.projDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.projDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Request
        if self.reqDelFrc == nil { self.reqDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequest.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequest> }
        self.syncToCloudCtx.perform {
            if self.reqDelFrc != nil, let xs = self.reqDelFrc.fetchedObjects {
                start = self.reqDelSyncIdx
                len = xs.count
                var req: ERequest!
                for i in start..<len {
                    req = xs[i]
                    delxs.append(req)
                    self.syncToCloudDeleteIds.insert(req.getId())
                    self.reqDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.reqDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Request data
        if self.reqDataDelFrc == nil { self.reqDataDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequestData.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequestData> }
        self.syncToCloudCtx.perform {
            if self.reqDataDelFrc != nil, let xs = self.reqDataDelFrc.fetchedObjects {
                start = self.reqDataDelSyncIdx
                len = xs.count
                var reqData: ERequestData!
                for i in start..<len {
                    reqData = xs[i]
                    delxs.append(reqData)
                    self.syncToCloudDeleteIds.insert(reqData.getId())
                    self.reqDataDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.reqDataDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Request body data
        if self.reqBodyDataDelFrc == nil { self.reqBodyDataDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequestBodyData.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequestBodyData> }
        self.syncToCloudCtx.perform {
            if self.reqBodyDataDelFrc != nil, let xs = self.reqBodyDataDelFrc.fetchedObjects {
                start = self.reqBodyDataDelSyncIdx
                len = xs.count
                var reqBodyData: ERequestBodyData!
                for i in start..<len {
                    reqBodyData = xs[i]
                    delxs.append(reqBodyData)
                    self.syncToCloudDeleteIds.insert(reqBodyData.getId())
                    self.reqBodyDataDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.reqBodyDataDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Request method data
        if self.reqMethodDataDelFrc == nil { self.reqMethodDataDelFrc = self.localdb.getDataMarkedForDelete(obj: ERequestMethodData.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<ERequestMethodData> }
        self.syncToCloudCtx.perform {
            if self.reqMethodDataDelFrc != nil, let xs = self.reqMethodDataDelFrc.fetchedObjects {
                start = self.reqMethodDataDelSyncIdx
                len = xs.count
                var reqMethodData: ERequestMethodData
                for i in start..<len {
                    reqMethodData = xs[i]
                    delxs.append(reqMethodData)
                    self.syncToCloudDeleteIds.insert(reqMethodData.getId())
                    self.reqMethodDataDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.reqMethodDataDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // File
        if self.fileDelFrc == nil { self.fileDelFrc = self.localdb.getDataMarkedForDelete(obj: EFile.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EFile> }
        self.syncToCloudCtx.perform {
            if self.fileDelFrc != nil, let xs = self.fileDelFrc.fetchedObjects {
                start = self.fileDelSyncIdx
                len = xs.count
                var file: EFile!
                for i in start..<len {
                    file = xs[i]
                    delxs.append(file)
                    self.syncToCloudDeleteIds.insert(file.getId())
                    self.fileDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.fileDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Image
        if self.imageDelFrc == nil { self.imageDelFrc = self.localdb.getDataMarkedForDelete(obj: EImage.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EImage> }
        self.syncToCloudCtx.perform {
            if self.imageDelFrc != nil, let xs = self.imageDelFrc.fetchedObjects {
                start = self.imageDelSyncIdx
                len = xs.count
                var image: EImage!
                for i in start..<len {
                    image = xs[i]
                    delxs.append(image)
                    self.syncToCloudDeleteIds.insert(image.getId())
                    self.imageDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.imageDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // History
        if self.histDelFrc == nil { self.histDelFrc = self.localdb.getDataMarkedForDelete(obj: EHistory.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EHistory> }
        self.syncToCloudCtx.perform {
            if self.histDelFrc != nil, let xs = self.histDelFrc.fetchedObjects {
                start = self.historyDelSyncIdx
                len = xs.count
                var history: EHistory!
                for i in start..<len {
                    history = xs[i]
                    delxs.append(history)
                    self.syncToCloudDeleteIds.insert(history.getId())
                    self.historyDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.historyDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Env
        if self.envDelFrc == nil { self.envDelFrc = self.localdb.getDataMarkedForDelete(obj: EEnv.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EEnv> }
        self.syncToCloudCtx.perform {
            if self.envDelFrc != nil, let xs = self.envDelFrc.fetchedObjects {
                start = self.envDelSyncIdx
                len = xs.count
                var env: EEnv!
                for i in start..<len {
                    env = xs[i]
                    delxs.append(env)
                    self.syncToCloudDeleteIds.insert(env.getId())
                    self.envDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.envDelSyncIdx < len { done = false }
            }
        }
        deleteEntities()
        // Env Variable
        if self.envVarDelFrc == nil { self.envVarDelFrc = self.localdb.getDataMarkedForDelete(obj: EEnvVar.self, ctx: self.syncToCloudCtx) as? NSFetchedResultsController<EEnvVar> }
        self.syncToCloudCtx.perform {
            if self.envVarDelFrc != nil, let xs = self.envVarDelFrc.fetchedObjects {
                start = self.envVarDelSyncIdx
                len = xs.count
                var envVar: EEnvVar!
                for i in start..<len {
                    envVar = xs[i]
                    delxs.append(envVar)
                    self.syncToCloudDeleteIds.insert(envVar.getId())
                    self.envVarDelSyncIdx += 1
                    if count == 7 { break }
                    count += 1
                }
                if done && self.envVarDelSyncIdx < len { done = false }
            }
        }
        self.deleteEntitesFromCloud(delxs, ctx: self.syncToCloudCtx)
        delxs = []
        if done { self.isSyncToCloudInProgress = false }
        // TODO: delete env, env vars
        Log.debug("sync to cloud queued - saves: \(self.syncToCloudSaveIds.count), deletes: \(self.syncToCloudDeleteIds.count)")
        self.checkSyncToCloudState()
    }
    
    func checkSyncToCloudState() {
        Log.debug("check sync to cloud state - saves: \(self.syncToCloudSaveIds.count), deletes: \(self.syncToCloudDeleteIds.count)")
        if !self.isSyncToCloudInProgress && self.syncToCloudSaveIds.isEmpty && self.syncToCloudDeleteIds.isEmpty && self.isSyncToCloudTriggered {
            self.destroySyncToCloudState()
        }
    }
    
    // MARK: - Sync from cloud
    
    func syncFromCloud() {
        Log.debug("sync from cloud")
        if self.syncFromCloudCtx == nil {
            self.syncFromCloudCtx = self.localdb.mainMOC
        }
        self.queryDefaultZoneRecords(completion: self.syncFromCloudHandler(_:))
    }
    
    func setLastSyncTime() {
        self.store.set(Date().currentTimeNanos(), forKey: self.lastSyncTimeKey)
    }
    
    func getLastSyncTime() -> Int {
        return self.store.integer(forKey: self.lastSyncTimeKey)
    }
    
    func handleSyncNotification(_ zoneID: CKRecordZone.ID) {
        self.fetchZoneChangesImp(zoneID: zoneID, isDelayedFetch: true)
    }
    
    func syncFromCloudHandler(_ result: Result<[CKRecord], Error>) {
        Log.debug("sync from cloud handler")
        self.syncToCloud()
        switch result {
        case .success(let records):
            Log.debug("sync from cloud handler: records \(records.count)")
            records.forEach { record in
                if !self.zonesToSyncInProgress.contains(record) {
                    self.zonesToSync.append(record)
                    self.zonesToSyncInProgress.insert(record)
                }
            }
            self.processZoneRecord()
        case .failure(let error):
            Log.error("Error syncing from cloud: \(error)")
            if let err = error as? CKError {
                if err.isUnknownItem() {
                    if let type = err.getRecordTypeForUnknownItem(), let recordType = RecordType[type], recordType == .zone {
                        let ctx = self.localdb.mainMOC
                        ctx.performAndWait {
                            if let ws = self.localdb.getWorkspace(id: self.localdb.defaultWorkspaceId, ctx: ctx) {
                                if !ws.isSyncEnabled { return }
                                Log.debug("Unknown item - Zone: default - saving")
                                self.saveZoneToCloud(ws)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func processZoneRecord() {
        Log.debug("process zone record: \(self.zonesToSync.map(\.recordID.recordName))")
        if self.zonesToSync.isEmpty {
            if !self.zonesToSyncInProgress.isEmpty { self.zonesToSyncInProgress = Set() }
            if self.hasMoreZonesToQuery { self.syncFromCloud() }
            return
        }
        let zone = self.zonesToSync.removeFirst()
        Log.debug("Processing zone: \(zone.recordID.recordName) for syncing")
        _ = self.syncRecordFromCloudHandler(zone)
    }
    
    func fetchZoneChangeCompleteHandler(_ zoneID: CKRecordZone.ID) {
        DispatchQueue.main.async {
            self.localdb.saveMainContext()
            self.nc.post(name: .zoneChangesDidSave, object: self, userInfo: [EACloudKit.zoneIDKey: zoneID])
            self.processZoneRecord()
        }
    }
    
    func fetchZoneChangesImp(zoneID: CKRecordZone.ID, isDelayedFetch: Bool) {
        self.fetchZoneChanges(zoneID: zoneID, isDelayedFetch: isDelayedFetch, completion: self.fetchZoneChangeCompleteHandler)
    }
    
    func syncRecordFromCloudHandler(_ record: CKRecord) -> Bool {
        switch RecordType(rawValue: record.type()) {
        case .zone:
            self.fetchZoneChanges(zoneID: self.ck.zoneID(workspaceId: record.id()), isDelayedFetch: false, completion: self.fetchZoneChangeCompleteHandler)
            fallthrough
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
        case .history:
            self.updateHistoryFromCloud(record)
        case .env:
            self.updateEnvFromCloud(record)
        case .envVar:
            self.updateEnvVarFromCloud(record)
        case .none:
            Log.error("Unknown record: \(record)")
        }
        return true
    }
    
    func subscribeToCloudKitEvents() {
        Log.debug("subscribe to cloudkit events")
        self.ck.subscribeToDBChanges(subId: SubscriptionId.databaseChange.rawValue)
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
        case .history:
            return SubscriptionId.historyChange.rawValue
        case .env:
            return SubscriptionId.envChange.rawValue
        case .envVar:
            return SubscriptionId.envVarChange.rawValue
        }
    }
    
    // MARK: - Cloud record merge (conflict)
    
    /// Check if server record is latest. Cases were a record is created locally, but failed to sync, new record gets added from another device, and then the
    /// former record gets saved, in which case the server copy is latest.
    func isServerLatest(local: CKRecord, server: CKRecord) -> Bool {
        if let lts = local["changeTag"] as? Int64, let rts = server["changeTag"] as? Int64 { return rts > lts }
        return false
    }
    
    func mergeWorkspace(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeProject(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRequest(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRequestBodyData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }

    func mergeRequestData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeRequestMethodData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeFileData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeImageData(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeHistory(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeEnv(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
    }
    
    func mergeEnvVar(local: CKRecord, server: CKRecord) -> CKRecord {
        return self.isServerLatest(local: local, server: server) ? server : local
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
        case .history:
            return self.mergeHistory(local: client, server: remote)
        case .env:
            return self.mergeEnv(local: client, server: remote)
        case .envVar:
            return self.mergeEnvVar(local: client, server: remote)
        }
    }
    
    // MARK: - Cloud record updated
    
    func updateWorkspaceFromCloud(_ record: CKRecord) {
        let wsId = record.id()
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            var aws = self.localdb.getWorkspace(id: wsId, ctx: ctx)
            var isNew = false
            if aws == nil {
                aws = self.localdb.createWorkspace(id: wsId, name: record.name(), desc: record.desc(), isSyncEnabled: record.isSyncEnabled(), ctx: ctx)
                isNew = true
            }
            guard let ws = aws else { return }
            if isNew || (ws.isSyncEnabled && (!ws.isActive || ws.changeTag < record.changeTag)) {  // => server has new copy
                ws.updateFromCKRecord(record)
                ws.isSynced = true
                ws.isActive = true
                self.localdb.saveMainContext()
                Log.debug("Workspace synced")
                self.nc.post(name: .workspaceDidSync, object: self)
            }
        }
    }
    
    func updateProjectFromCloud(_ record: CKRecord) {
        let projId = record.id()
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            var aproj = self.localdb.getProject(id: projId, ctx: ctx)
            var isNew = false
            if aproj == nil {
                aproj = self.localdb.createProject(id: record.id(), wsId: record.getWsId(), name: record.name(), desc: record.desc(), checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let proj = aproj else { return }
            if isNew || proj.changeTag < record.changeTag {  // => server has new copy
                proj.updateFromCKRecord(record, ctx: ctx)
                if self.localdb.getRequestMethodData(id: "rm\(proj.getId())-GET", ctx: ctx) == nil {
                    _ = self.localdb.genDefaultRequestMethods(proj, ctx: ctx)
                }
                proj.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Project synced")
                self.nc.post(name: .projectDidSync, object: self)
            }
        }
    }
    
    func updateRequestFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            guard let ref = record["project"] as? CKRecord.Reference, let proj = EProject.getProjectFromReference(ref, record: record, ctx: ctx) else { return }
            let reqId = record.id()
            var areq = self.localdb.getRequest(id: reqId, ctx: ctx)
            var isNew = false
            if areq == nil {
                areq = self.localdb.createRequest(id: record.id(), wsId: record.getWsId(), name: record.name(), project: proj, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let req = areq else { return }
            if isNew || req.changeTag < record.changeTag {  // => server has new copy
                req.updateFromCKRecord(record, ctx: ctx)
                req.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Request synced")
                self.nc.post(name: .requestDidSync, object: self)
            }
        }
    }
        
    func updateRequestBodyDataFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let reqId = record.id()
            var aReqBodyData = self.localdb.getRequestBodyData(id: reqId, ctx: ctx)
            var isNew = false
            if aReqBodyData == nil {
                aReqBodyData = self.localdb.createRequestBodyData(id: record.id(), wsId: record.getWsId(), checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let reqBodyData = aReqBodyData else { return }
            if isNew || reqBodyData.changeTag < record.changeTag {  // => server has new copy
                reqBodyData.updateFromCKRecord(record, ctx: ctx)
                reqBodyData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Request body synced")
                self.nc.post(name: .requestBodyDataDidSync, object: self)
            }
        }
    }
    
    func updateRequestDataFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            guard let type = ERequestData.getRecordType(record) else { return }
            let fieldType = ERequestData.getFormFieldFormatType(record)
            let reqId = record.id()
            var aData = self.localdb.getRequestData(id: reqId, ctx: ctx)
            var isNew = false
            if aData == nil {
                aData = self.localdb.createRequestData(id: reqId, wsId: record.getWsId(), type: type, fieldFormat: fieldType, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let reqData = aData else { return }
            if isNew || reqData.changeTag < record.changeTag {  // => server has new copy
                reqData.updateFromCKRecord(record, ctx: ctx)
                reqData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Request data synced")
                self.nc.post(name: .requestDataDidSync, object: self)
            }
        }
    }
    
    func updateRequestMethodDataFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let reqMethodDataId = record.id()
            var aReqMethodData = self.localdb.getRequestMethodData(id: reqMethodDataId, ctx: ctx)
            var isNew = false
            if aReqMethodData == nil {
                aReqMethodData = self.localdb.createRequestMethodData(id: reqMethodDataId, wsId: record.getWsId(), name: record.name(), isCustom: true, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let reqMethodData = aReqMethodData else { return }
            if isNew || reqMethodData.changeTag < record.changeTag {  // => server has new copy
                reqMethodData.updateFromCKRecord(record, ctx: ctx)
                reqMethodData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Request method data synced")
                self.nc.post(name: .requestMethodDataDidSync, object: self)
            }
        }
    }
    
    func updateFileDataFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let fileId = record.id()
            var aFileData = self.localdb.getFileData(id: fileId, ctx: ctx)
            var isNew = false
            if aFileData == nil {
                aFileData = self.localdb.createFile(data: Data(), wsId: record.getWsId(), name: record.name(), path: URL(fileURLWithPath: "/tmp/"), checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let fileData = aFileData else { return }
            if isNew || fileData.changeTag < record.changeTag {  // => server has new copy
                fileData.updateFromCKRecord(record, ctx: ctx)
                fileData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("File data synced")
                self.nc.post(name: .fileDataDidSync, object: self)
            }
        }
    }
    
    func updateImageDataFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let fileId = record.id()
            var aImageData = self.localdb.getImageData(id: fileId, ctx: ctx)
            var isNew = false
            if aImageData == nil {
                aImageData = self.localdb.createImage(data: Data(), wsId: record.getWsId(), name: record.name(), type: ImageType.jpeg.rawValue, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let imageData = aImageData else { return }
            if isNew || imageData.changeTag < record.changeTag {  // => server has new copy
                imageData.updateFromCKRecord(record, ctx: ctx)
                imageData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Image data synced")
                self.nc.post(name: .imageDataDidSync, object: self)
            }
        }
    }
    
    func updateHistoryFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let histId = record.id()
            let wsId = record.getWsId()
            var hist = self.localdb.getHistory(id: histId, ctx: ctx)
            var isNew = false
            if hist == nil {
                hist = self.localdb.createHistory(id: histId, wsId: wsId, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let histData = hist else { return }
            if isNew || histData.changeTag < record.changeTag {  // => server has new copy
                histData.updateFromCKRecord(record, ctx: ctx)
                histData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("History data synced")
                self.nc.post(name: .historyDidSync, object: self)
            }
        }
    }
    
    func updateEnvFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let envId = record.id()
            let name = record["name"] as? String ?? ""
            var env = self.localdb.getEnv(id: envId, ctx: ctx)
            var isNew = false
            if env == nil {
                env = self.localdb.createEnv(name: name, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let envData = env else { return }
            if isNew || envData.changeTag < record.changeTag {  // => server has new copy
                envData.updateFromCKRecord(record, ctx: ctx)
                envData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("Env data synced")
                self.nc.post(name: .envDidSync, object: self)
            }
        }
    }
    
    func updateEnvVarFromCloud(_ record: CKRecord) {
        let ctx = self.syncFromCloudCtx!
        ctx.performAndWait {
            let envVarId = record.id()
            var envVar = self.localdb.getEnvVar(id: envVarId, ctx: ctx)
            var isNew = false
            if envVar == nil {
                envVar = self.localdb.createEnvVar(id: envVarId, checkExists: false, ctx: ctx)
                isNew = true
            }
            guard let envVarData = envVar else { return }
            if isNew || envVarData.changeTag < record.changeTag {  // => server has new copy
                envVarData.updateFromCKRecord(record, ctx: ctx)
                envVarData.isSynced = true
                self.localdb.saveMainContext()
                Log.debug("EnvVar data synced")
                self.nc.post(name: .envVarDidSync, object: self)
            }
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
        case .history:
            self.updateHistoryFromCloud(record)
        case .env:
            self.updateEnvFromCloud(record)
        case .envVar:
            self.updateEnvVarFromCloud(record)
        case .none:
            Log.error("Unknown record: \(record)")
        }
    }
    
    // MARK: - Cloud record deleted
    
    func workspaceDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        ctx.perform {
            if id == self.localdb.defaultWorkspaceId {
                let ws = self.localdb.getDefaultWorkspace(ctx: ctx)
                ws.resetToDefault()
                ws.isSynced = true
                self.localdb.saveMainContext()
                return
            }
            self.localdb.deleteWorkspace(id: id, ctx: ctx)
        }
    }
    
    func projectDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteProject(id: id, ctx: ctx)
    }
    
    func requestDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteRequest(id: id, ctx: ctx)
    }
        
    func requestBodyDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteRequestBodyData(id: id, ctx: ctx)
    }
    
    func requestDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteRequestData(id: id, ctx: ctx)
    }
    
    func requestMethodDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteRequestMethodData(id: id, ctx: ctx)
    }
    
    func fileDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteFileData(id: id, ctx: ctx)
    }
    
    func imageDataDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteImageData(id: id, ctx: ctx)
    }
    
    func historyDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteHistory(id: id, ctx: ctx)
    }
    
    func envDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteEnv(id: id, ctx: ctx)
    }
    
    func envVarDidDeleteFromCloud(_ id: String) {
        let ctx = self.syncFromCloudCtx!
        self.localdb.deleteEnvVar(id: id, ctx: ctx)
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
        case .history:
            self.historyDidDeleteFromCloud(id)
        case .env:
            self.envDidDeleteFromCloud(id)
        case .envVar:
            self.envVarDidDeleteFromCloud(id)
        case .zone:
            break
        case .none:
            Log.error("Unknown record type: \(id)")
        }
        self.localdb.saveMainContext()
    }
    
    func cloudRecordsDidDelete(_ recordsIDs: [CKRecord.ID]) {
        recordsIDs.forEach { self.cloudRecordDidDelete($0) }
    }
    
    // MARK: - Local record deleted
    
    /// Delete data marked for delete. Used mainly after edit request.
    /// - Parameters:
    ///   - set: The entities deleted in the edit request.
    ///   - request: The request object.
    func deleteDataMarkedForDelete(_ set: Set<EditRequestInfo>) {
        Log.debug("delete data marked for delete - set: \(set.count)")
        guard set.count > 0 else { return }
        let ctx = self.localdb.mainMOC
        ctx.perform {
            let xs = set.toArray().compactMap({ info -> Entity? in
                self.localdb.getManagedObject(moId: info.moID, withContext: ctx) as? Entity
            })
            self.deleteEntitesFromCloud(xs)
            App.shared.clearEditRequestDeleteObjects()
        }
    }
    
    /// Delete the record and nested records. Here if a parent entity is marked for delete, the child entites are not marked, but we need to delete them as well.
    /// - Parameters:
    ///   - ws: The workspace.
    ///   - ctx: A managed object context.
    func deleteDataMarkedForDelete(_ ws: EWorkspace, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete data marked for delete - ws")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            let xs = self.localdb.getProjects(wsId: ws.getId(), includeMarkForDelete: true, ctx: ctx)
            xs.forEach { proj in self.deleteDataMakedForDelete(proj, ctx: ctx) }
        }
        self.deleteEntitesFromCloud([ws], ctx: ctx)
    }
    
    func deleteDataMakedForDelete(_ proj: EProject, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete data marked for delete - proj")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            let xs = self.localdb.getRequests(projectId: proj.getId(), includeMarkForDelete: true, ctx: ctx)
            xs.forEach { req in self.deleteDataMarkedForDelete(req, ctx: ctx) }
        }
        self.deleteEntitesFromCloud([proj], ctx: ctx)
    }
    
    func deleteDataMarkedForDelete(_ request: ERequest, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete data marked for delete - req")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            guard let ws = request.project?.workspace else { return }
            if request.markForDelete {
                var acc: [Entity] = []
                acc.append(request)
                if let xs = request.headers?.allObjects as? [ERequestData] { acc.append(contentsOf: xs) }
                if let xs = request.params?.allObjects as? [ERequestData] { acc.append(contentsOf: xs) }
                if let body = request.body {
                    if let xs = body.form?.allObjects as? [ERequestData] {
                        xs.forEach { reqData in
                            if let files = reqData.files?.allObjects as? [EFile] { acc.append(contentsOf: files) }
                            if let image = reqData.image { acc.append(image) }
                            acc.append(reqData)
                        }
                    }
                    if let xs = body.multipart?.allObjects as? [ERequestData] { acc.append(contentsOf: xs) }
                    if let bin = body.binary {
                        if let xs = bin.files?.allObjects as? [EFile] { acc.append(contentsOf: xs) }
                        if let image = bin.image { acc.append(image) }
                        acc.append(bin)
                    }
                    acc.append(body)
                }
                self.deleteEntitesFromCloud(acc, ctx: ctx)
            } else {
                self.deleteRequestDataMarkedForDelete(reqId: request.getId(), wsId: ws.getId(), ctx: ctx)
                self.deleteRequestBodyDataMarkedForDelete(request, ctx: ctx)
            }
        }
        self.deleteRequestMethodDataMarkedForDelete(request, ctx: ctx)
    }
    
    func deleteRequestDataMarkedForDelete(reqId: String, wsId: String, ctx: NSManagedObjectContext? = nil) {
        Log.debug("delete request data marked for delete: reqId: \(reqId)")
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            var files: [EFile] = []
            var xs = self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .header, ctx: ctx)
            xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .param, ctx: ctx))
            xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .form, ctx: ctx))
            xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .multipart, ctx: ctx))
            xs.append(contentsOf: self.localdb.getRequestDataMarkedForDelete(reqId: reqId, type: .binary, ctx: ctx))
            xs.forEach { reqData in
                files.append(contentsOf: self.localdb.getFilesMarkedForDelete(reqDataId: reqData.getId(), ctx: ctx))
                self.deleteDataMarkedForDelete(reqData.image, wsId: wsId)
            }
            self.deleteEntitesFromCloud(files, ctx: ctx)
            self.deleteEntitesFromCloud(xs, ctx: ctx)
        }
    }
    
    func deleteDataMarkedForDelete(_ files: [EFile], wsId: String, ctx: NSManagedObjectContext? = nil) {
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        self.deleteEntitesFromCloud(files, ctx: ctx)
    }
    
    func deleteDataMarkedForDelete(_ image: EImage?, wsId: String, ctx: NSManagedObjectContext? = nil) {
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            guard let image = image, image.markForDelete else { return }
            self.deleteEntitesFromCloud([image], ctx: ctx)
        }
    }
    
    func deleteRequestBodyDataMarkedForDelete(_ req: ERequest, ctx: NSManagedObjectContext? = nil) {
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            if let body = req.body, body.markForDelete {
                self.deleteEntitesFromCloud([body], ctx: ctx)
            }
        }
    }
    
    func deleteRequestMethodDataMarkedForDelete(_ req: ERequest, ctx: NSManagedObjectContext? = nil) {
        let ctx = ctx != nil ? ctx! : self.localdb.getChildMOC()
        ctx.perform {
            if let proj = req.project {
                self.deleteEntitesFromCloud(self.localdb.getRequestMethodDataMarkedForDelete(projId: proj.getId(), ctx: self.localdb.getChildMOC()), ctx: ctx)
            }
        }
    }
    
    private func deleteEntitesFromCloud(_ xs: [Entity], ctx: NSManagedObjectContext? = nil) {
        if xs.isEmpty { return }
        var xs = xs
        Log.debug("delete data count: \(xs.count)")
        var recordIDs: [CKRecord.ID] = []
        xs.forEach { elem in
            elem.managedObjectContext?.performAndWait { recordIDs.append(elem.getRecordID()) }
        }
        let op = EACloudOperation(deleteRecordIDs: recordIDs) { [weak self] op in
            self?.ck.deleteRecords(recordIDs: recordIDs) { result in
                op?.finish()
                switch result {
                case .success(let deleted):
                    Log.debug("Delete records: \(deleted)")
                    let lock = NSLock()
                    var count = 0
                    let len = deleted.count
                    deleted.forEach { recordID in
                        if let idx = (recordIDs.firstIndex { oRecordID -> Bool in oRecordID == recordID }) {
                            let elem = xs[idx]
                            xs.remove(at: idx)
                            recordIDs.remove(at: idx)
                            if let ctx = elem.managedObjectContext {
                                ctx.performAndWait {
                                    self?.syncToCloudDeleteIds.remove(elem.getId())
                                    Log.debug("Entity deleted from local: \(elem.getId())")
                                    self?.localdb.deleteEntity(elem)
                                    lock.lock()
                                    count += 1
                                    lock.unlock()
                                    if count == len { self?.checkSyncToCloudState() }
                                }
                            }
                        }
                    }
                    Log.debug("Remaining entities to delete: \(xs.count)")
                case .failure(let error):
                    self?.checkSyncToCloudState()
                    Log.error("Error deleting records: \(error)")
                }
            }
        }
        if !self.opQueue.add(op) { self.addSyncOpToLocal(op) }
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
                self.isSyncFromCloudSuccess = true
                if let cursor = cursor {
                    self.setDefaultZoneQueryCursorToCache(cursor)
                    self.hasMoreZonesToQuery = true
                } else {
                    self.removeDefaultZoneQueryCursorFromCache()
                    self.hasMoreZonesToQuery = false
                }
                completion(.success(records))
            case .failure(let error):
                Log.error("Error querying default zone record: \(error)")
                self.isSyncFromCloudSuccess = false
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch
    
    func fetchZoneChanges(zoneID: CKRecordZone.ID, isDelayedFetch: Bool? = false, completion: ((CKRecordZone.ID) -> Void)? = nil) {
        Log.debug("fetching zone changes for zoneID: \(zoneID.zoneName) - isDelayedFetch: \(isDelayedFetch ?? false)")
        let fn: () -> Void = {
            self.ck.fetchZoneChanges(zoneID: zoneID, handler: { result in
                Log.debug("zone change handler")
                switch result {
                case .success(let (saved, deleted)):
                    if let x = saved {
                        Log.debug("zone change - saved: \(x)")
                        self.cloudRecordDidChange(x)
                    }
                    if let x = deleted {
                        Log.debug("zone change - delete: \(x)")
                        self.cloudRecordDidDelete(x)
                    }
                case .failure(let error):
                    Log.error("Error getting zone changes: \(error)")
                }
            }, completion: completion)
        }
        if isDelayedFetch != nil, isDelayedFetch! {
            if self.fetchZoneChangesDelayTimer == nil {
                self.fetchZoneChangesDelayTimer = EARescheduler(interval: 4.0, type: .everyFn, limit: 4)
                Log.debug("Delayed fetch of zones initialised")
            }
            self.fetchZoneChangesDelayTimer.schedule(fn: EAReschedulerFn(id: "fetch-zone-changes", block: {
                fn()
                Log.debug("Delayed exec - fetch zones")
                return true
            }, callback: { _ in
                self.fetchZoneChangesDelayTimer = nil
                Log.debug("Delayed fetch exec - done")
            }, args: []))
        } else {
            fn()
        }
    }
    
    /// Checks if the record is present in cache. If present, returns, else fetch from cloud, adds to the cache and returns.
    func fetchRecord(_ entity: Entity, type: RecordType, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        var id: String!
        (entity as NSManagedObject).managedObjectContext?.performAndWait { id = entity.getId() }
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
        var id: String!
        (entity as NSManagedObject).managedObjectContext?.performAndWait { id = entity.getId() }
        self.saveQueue.enqueue(DeferredSaveModel(record: record, entity: entity, id: id, completion: completion))
    }
    
    func saveToCloud(_ models: [DeferredSaveModel]) {
        self.saveQueue.enqueue(models)
    }
    
    func removeFromSyncToCloudSaveId(_ id: String) {
        self.syncToCloudSaveIds.remove(id)
    }
    
    func saveZoneToCloud(_ ws: EWorkspace) {
        let zoneModel = self.zoneDeferredSaveModel(ws: ws)
        self.saveToCloud([zoneModel])
    }
    
    /// Saves the given workspace to the cloud
    func saveWorkspaceToCloud(_ ws: EWorkspace) {
        ws.managedObjectContext?.perform {
            if !ws.isSyncEnabled { self.removeFromSyncToCloudSaveId(ws.getId()); return }
            if ws.markForDelete { self.deleteDataMarkedForDelete(ws); return }
            let wsId = ws.getId()
            let zoneID = ws.getZoneID()
            let recordID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
            let record = self.ck.createRecord(recordID: recordID, recordType: RecordType.workspace.rawValue)
            ws.updateCKRecord(record)
            let wsModel = DeferredSaveModel(record: record, entity: ws, id: wsId)
            let zoneModel = self.zoneDeferredSaveModel(ws: ws)
            self.saveToCloud([wsModel, zoneModel])
        }
    }
    
    /// Save the given project and updates the associated workspace to the cloud.
    func saveProjectToCloud(_ proj: EProject) {
        let ctx = proj.managedObjectContext ?? self.localdb.mainMOC
        ctx.perform {
            if proj.workspace == nil {
                if let ws = self.localdb.getWorkspace(id: proj.getWsId(), ctx: ctx) { proj.workspace = ws }
            }
            guard let ws = proj.workspace else { self.removeFromSyncToCloudSaveId(proj.getId()); Log.error("Workspace is empty for project"); return }
            if !ws.isSyncEnabled { self.removeFromSyncToCloudSaveId(proj.getId()); return }
            if ws.markForDelete { self.deleteDataMarkedForDelete(ws); return }
            if proj.markForDelete { self.deleteDataMakedForDelete(proj); return }
            let wsId  = ws.getId()
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
                                    ctx.perform {
                                        let ckwsID = self.ck.recordID(entityId: wsId, zoneID: zoneID)
                                        let ckws = self.ck.createRecord(recordID: ckwsID, recordType: RecordType.workspace.rawValue)
                                        ws.updateCKRecord(ckws)
                                        self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws, isCreateZoneRecord: true)
                                    }
                                case .failure(let error):
                                    Log.error("Error creating zone: \(error)")
                                }
                            }
                        } else if err.isRecordNotFound() {
                            let ckws = self.ck.createRecord(recordID: self.ck.recordID(entityId: wsId, zoneID: ckproj.zoneID()), recordType: RecordType.workspace.rawValue)
                            self.saveProjectToCloudImp(ckproj: ckproj, proj: proj, ckws: ckws, ws: ws)
                        }
                    }
                }
            }
        }
    }
    
    /// Save the given request and updates the associated project to the cloud.
    func saveRequestToCloud(_ req: ERequest) {
        req.managedObjectContext?.perform {
            guard let proj = req.project, let ws = proj.workspace, ws.isSyncEnabled else { self.removeFromSyncToCloudSaveId(req.getId()); return }
            if proj.markForDelete { self.deleteDataMakedForDelete(proj); return }
            if req.markForDelete { self.deleteDataMarkedForDelete(req); return }
            guard let reqId = req.id else { Log.error("ERequest id is nil"); return }
            let wsId = ws.getId()
            let projId = proj.getId()
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
    }
    
    func saveHistoryToCloud(_ hist: EHistory) {
        hist.managedObjectContext?.perform {
            let zoneID = self.ck.zoneID(workspaceId: hist.getWsId())
            let ckHistID = self.ck.recordID(entityId: hist.getId(), zoneID: zoneID)
            let ckHist = self.ck.createRecord(recordID: ckHistID, recordType: hist.recordType)
            hist.updateCKRecord(ckHist)
            self.saveToCloud(record: ckHist, entity: hist)
        }
    }
    
    func saveEnvToCloud(_ env: EEnv) {
        env.managedObjectContext?.perform {
            let zoneID = self.ck.appZoneID()
            let ckEnvID = self.ck.recordID(entityId: env.getId(), zoneID: zoneID)
            let ckEnv = self.ck.createRecord(recordID: ckEnvID, recordType: env.recordType)
            env.updateCKRecord(ckEnv)
            self.saveToCloud(record: ckEnv, entity: env)
        }
    }

    func saveEnvVarToCloud(_ envVar: EEnvVar) {
        envVar.managedObjectContext?.perform {
            let zoneID = self.ck.appZoneID()
            let ckEnvVarID = self.ck.recordID(entityId: envVar.getId(), zoneID: zoneID)
            let ckEnvVar = self.ck.createRecord(recordID: ckEnvVarID, recordType: envVar.recordType)
            guard let env = envVar.env else { return }
            // env record
            let ckEnvID = self.ck.recordID(entityId: env.getId(), zoneID: zoneID)
            let ckEnv = self.ck.createRecord(recordID: ckEnvID, recordType: env.recordType)
            env.updateCKRecord(ckEnv)
            envVar.updateCKRecord(ckEnvVar, env: ckEnv)
            self.saveToCloud(record: ckEnvVar, entity: envVar)
        }
    }
    
    func zoneDeferredSaveModel(ws: EWorkspace) -> DeferredSaveModel {
        var ckzn: CKRecord!
        var wsId: String!
        ws.managedObjectContext?.performAndWait {
            wsId = ws.getId()
            let zone = Zone(id: wsId, name: ws.getName(), desc: ws.desc ?? "", isSyncEnabled: ws.isSyncEnabled, created: ws.created, modified: ws.modified, changeTag: ws.changeTag, version: ws.version)
            let recordID = self.ck.recordID(entityId: wsId, zoneID: self.ck.defaultZoneID())
            ckzn = self.ck.createRecord(recordID: recordID, recordType: RecordType.zone.rawValue)
            zone.updateCKRecord(ckzn)
        }
        return DeferredSaveModel(record: ckzn, id: wsId)
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveProjectToCloudImp(ckproj: CKRecord, proj: EProject, ckws: CKRecord, ws: EWorkspace, isCreateZoneRecord: Bool? = false) {
        proj.managedObjectContext?.perform {
            proj.updateCKRecord(ckproj, workspace: ckws)
            let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
            let wsModel = DeferredSaveModel(record: ckws, entity: ws, id: ws.getId())
            if let createZoneRecord = isCreateZoneRecord, createZoneRecord {
                self.saveToCloud([projModel, wsModel, self.zoneDeferredSaveModel(ws: ws)])
            } else {
                self.saveToCloud([projModel, wsModel])
            }
        }
    }
    
    /// Saves the given request and corresponding project to the cloud.
    func saveRequestToCloudImp(ckreq: CKRecord, req: ERequest, ckproj: CKRecord, proj: EProject) {
        req.managedObjectContext?.perform {
            var acc: [DeferredSaveModel] = []
            let zoneID = ckreq.zoneID()
            guard let wsId = req.project?.workspace?.getId() else { return }
            req.updateCKRecord(ckreq, project: ckproj)
            let projModel = DeferredSaveModel(record: ckproj, entity: proj, id: proj.getId())
            let reqModel = DeferredSaveModel(record: ckreq, entity: req, id: req.getId())
            acc.append(contentsOf: [projModel, reqModel])
            if let methods = proj.requestMethods?.allObjects as? [ERequestMethodData], methods.count > 0 {
                methods.forEach { method in
                    if method.markForDelete { self.deleteRequestMethodDataMarkedForDelete(req); return}
                    if method.isCustom && !method.isSynced {
                        let ckmeth = self.ck.createRecord(recordID: self.ck.recordID(entityId: method.getId(), zoneID: zoneID), recordType: RecordType.requestMethodData.rawValue)
                        method.updateCKRecord(ckmeth, project: ckproj)
                        acc.append(DeferredSaveModel(record: ckmeth, id: ckmeth.id()))
                    }
                }
            }
            if let set = req.headers, let xs = set.allObjects as? [ERequestData] {
                xs.forEach { reqData in
                    if reqData.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
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
                        if reqData.markForDelete {
                            self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId);
                            return
                        }
                        let paramrecord = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                        reqData.updateCKRecord(paramrecord)
                        ERequestData.addRequestReference(ckreq, toParam: paramrecord)
                        acc.append(DeferredSaveModel(record: paramrecord, id: reqData.getId()))
                    }
                }
            }
            if let body = req.body {
                if body.markForDelete { self.deleteRequestBodyDataMarkedForDelete(req); return }
                let ckbody = self.ck.createRecord(recordID: self.ck.recordID(entityId: body.getId(), zoneID: zoneID), recordType: RecordType.requestBodyData.rawValue)
                if !body.isSynced {
                    body.updateCKRecord(ckbody, request: ckreq)
                    acc.append(DeferredSaveModel(record: ckbody, id: ckbody.id()))
                }
                if let binary = body.binary {
                    if binary.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                    let ckbin = self.ck.createRecord(recordID: self.ck.recordID(entityId: binary.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                    if let files = binary.files?.allObjects as? [EFile] {
                        var delxs: [EFile] = []
                        files.forEach { file in
                            if !file.isSynced {
                                if file.markForDelete {
                                    delxs.append(file)
                                } else {
                                    let ckfile = self.ck.createRecord(recordID: self.ck.recordID(entityId: file.getId(), zoneID: zoneID), recordType: RecordType.file.rawValue)
                                    file.updateCKRecord(ckfile)
                                    EFile.addRequestDataReference(ckfile, reqData: ckbin)
                                    acc.append(DeferredSaveModel(record: ckfile, id: ckfile.id()))
                                }
                            }
                        }
                        if delxs.count > 0 { self.deleteDataMarkedForDelete(delxs, wsId: wsId) }
                    }
                    if let image = binary.image, !image.isSynced {
                        if image.markForDelete { self.deleteDataMarkedForDelete(image, wsId: wsId); return }
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
                        if reqData.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                        let ckform = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                        if !reqData.isSynced {
                            reqData.updateCKRecord(ckform)
                            ERequestData.addRequestBodyDataReference(ckbody, toForm: ckform, type: .form)
                            acc.append(DeferredSaveModel(record: ckform, id: ckform.id()))
                        }
                        if let files = reqData.files?.allObjects as? [EFile] {
                            var delxs: [EFile] = []
                            files.forEach { file in
                                if file.markForDelete { delxs.append(file); return }
                                if !file.isSynced {
                                    let ckfile = self.ck.createRecord(recordID: self.ck.recordID(entityId: file.getId(), zoneID: zoneID), recordType: RecordType.file.rawValue)
                                    file.updateCKRecord(ckfile)
                                    EFile.addRequestDataReference(ckfile, reqData: ckform)
                                    acc.append(DeferredSaveModel(record: ckfile, id: ckfile.id()))
                                }
                            }
                            if delxs.count > 0 { self.deleteDataMarkedForDelete(delxs, wsId: wsId) }
                        }
                        if let image = reqData.image, !image.isSynced {
                            if image.markForDelete { self.deleteDataMarkedForDelete(image, wsId: wsId); return }
                            let ckimage = self.ck.createRecord(recordID: self.ck.recordID(entityId: image.getId(), zoneID: zoneID), recordType: RecordType.image.rawValue)
                            image.updateCKRecord(ckimage)
                            EImage.addRequestDataReference(ckform, image: ckimage)
                            acc.append(DeferredSaveModel(record: ckimage, id: ckimage.id()))
                        }
                    }
                }
                if let multipart = body.multipart?.allObjects as? [ERequestData] {
                    multipart.forEach { reqData in
                        if reqData.markForDelete { self.deleteRequestDataMarkedForDelete(reqId: req.getId(), wsId: wsId); return }
                        if !reqData.isSynced {
                            let ckmpart = self.ck.createRecord(recordID: self.ck.recordID(entityId: reqData.getId(), zoneID: zoneID), recordType: RecordType.requestData.rawValue)
                            reqData.updateCKRecord(ckmpart)
                            ERequestData.addRequestBodyDataReference(ckbody, toForm: ckmpart, type: .multipart)
                            acc.append(DeferredSaveModel(record: ckmpart, id: ckmpart.id()))
                        }
                    }
                }
            }
            self.saveToCloud(acc)  // we need to save this in the same request so that the deps are created and referenced properly.
        }
    }
}
